"""Sample native wounded poses; write manifests/TRES metadata, never edit PNGs."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DIRS=('se','sw','ne','nw')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def cuts(alpha,count):
    w,h=alpha.size;result=[0]
    for index in range(1,count):
        bands=[]
        for x in range(int(w*(index/count-.07)),int(w*(index/count+.07))):
            if sum(alpha.crop((x,0,x+1,h)).histogram()[16:])==0:
                if not bands or x>bands[-1][-1]+1:bands.append([x])
                else:bands[-1].append(x)
        bands=[b for b in bands if len(b)>=4];assert bands,'No safe gutter'
        b=min(bands,key=lambda b:abs((b[0]+b[-1])/2-w*index/count))
        result.append((b[0]+b[-1])//2)
    return result+[w]
def grid(alpha,count):
    # Transpose is a read-only mask view used to find horizontal empty gutters.
    xs=cuts(alpha,count);ys=cuts(alpha.transpose(Image.Transpose.TRANSPOSE),count)
    return [[xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y]] for y in range(count) for x in range(count)]
selection={
    'base':'assets/characters/shi_qian_wounded_20261005/idle_walk.png',
    'step_b_se':'assets/characters/shi_qian_wounded_20261005/native_references/opposite_step_se_only.png',
    'step_b_sw':'assets/characters/shi_qian_wounded_20261005/step_b_sw.png',
    'step_b_ne':'assets/characters/shi_qian_wounded_20261005/step_b_ne.png',
    'step_b_nw':'assets/characters/shi_qian_wounded_20261005/step_b_nw.png'}
review=ROOT/'qa/zhu_wounded_20261005/user_proportion_review.json'
if review.is_file():
    rejected={r['sha256'] for r in json.loads(review.read_text(encoding='utf-8'))['rejected_candidates']}
    assert all(sha(ROOT/p) not in rejected for p in selection.values()),'Old human proportions were rejected; revise selected native sources before rebuilding.'
sources={};masks={};rects={}
for name,path in selection.items():
    im=Image.open(ROOT/path);assert im.mode=='RGBA' and max(im.size)<=1536
    a=im.getchannel('A');masks[name]=a
    regions=grid(a,4 if name=='base' else 2) if name in ['base','step_b_se'] else [[0,0,*im.size]]
    rects[name]=regions
    unused=([{'region':regions[i],'reason':'Rejected repeated leading-leg phase; replaced by independent opposite step'} for i in [3,7,11,15]] if name=='base' else [{'region':r,'reason':'Other directions failed opposite-step review; only SE selected'} for r in regions[1:]] if name=='step_b_se' else [])
    sources[name]={'path':path,'sha256':sha(ROOT/path),'job':name,'mode':'RGBA','native_size':list(im.size),'import_limit':1536,'imported_size':list(im.size),'full_atlas':not unused,'alpha_zero_fraction':a.histogram()[0]/(im.width*im.height),'unused_regions':unused}
manifest={'schema':'native_direction4_spriteframes_v1','character':'zhu_wounded_shi_qian','sources':sources,'states':{'idle':['idle'],'walk':['walk_a','passing','walk_b','passing']},'poses':{},'resources':[],'scope':'Shi Qian unarmed wounded idle and alternating careful walk only. Other six pending. Runtime rescue, terminal clothing and scale/pivot review required.'}
checks=[]
for row,direction in enumerate(DIRS):
    for column,pose in enumerate(['idle','walk_a','passing','walk_b']):
        source='base' if column<3 else 'step_b_'+direction
        region=rects[source][row*4+column] if column<3 else rects[source][0]
        x,y,w,h=region;a=masks[source].crop((x,y,x+w,y+h));bbox=a.point(lambda v:255 if v>16 else 0).getbbox();assert bbox
        left,top,right,bottom=bbox;clearance=min(left,top,w-right,h-bottom);assert clearance>=4
        virtual=max(w,h);padx=(virtual-w)//2;pady=(virtual-h)//2
        feet=a.crop((0,bottom-int((bottom-top)*.23),w,bottom)).point(lambda v:255 if v>16 else 0).getbbox();assert feet
        pivot=[(feet[0]+feet[2])/2,bottom-4]
        name=pose+'_'+direction
        manifest['poses'][name]={'source':source,'region_raw':region,'region':region,'margin':[padx,pady,virtual-w,virtual-h],'virtual_size_imported':virtual,'pivot':pivot,'draw_offset_px':[virtual*.5-(padx+pivot[0]),virtual*.82-(pady+pivot[1])],'draw_scale':round(virtual*.78/(bottom-top),6)}
        checks.append({'pose':name,'bounds':list(bbox),'clearance_px':clearance,'passed':True,'foot_anchor':'Initial lower-silhouette contact estimate; runtime review can require authored correction'})
    for state in ['idle','walk']:manifest['resources'].append(f'assets/anim/zhu_wounded_shi_qian_{state}_{direction}.tres')
write(ROOT/'assets/direction4/zhu_wounded_shi_qian_20261005.json',manifest)
write(ROOT/'qa/zhu_wounded_20261005/shi_qian_bounds_audit.json',{'passed':True,'native_pixel_edits':False,'checks':checks,'scope':'Native sampling/clearance only; movement and art acceptance pending'})
write(HERE/'selection.json',{'sources':selection,'authored_poses':16,'states':manifest['states'],'scope':manifest['scope']})
print(json.dumps({'sources':len(sources),'poses':16,'resources':8,'native_pixel_edits':False}))
