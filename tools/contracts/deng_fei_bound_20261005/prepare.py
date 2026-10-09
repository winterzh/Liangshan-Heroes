"""Prepare four standing bound-deng_fei idle samples and lineage; never edit PNGs."""
from pathlib import Path
import hashlib, json
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
TAG='bound_deng_fei_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
jobs=json.loads((HERE/'jobs.json').read_text(encoding='utf-8'))
for job in jobs:assert sha(ROOT/job['repository_input'])==job['sha256']
job=next(j for j in jobs if j['selected'])
im=Image.open(ROOT/job['repository_input'])
assert im.mode=='RGBA' and max(im.size)<=1536
alpha=im.getchannel('A');w,h=im.size
def gap(size,empty):
    bands=[]
    for i in range(int(size*.32),int(size*.68)):
        if empty(i):
            if not bands or i>bands[-1][-1]+1:bands.append([i])
            else:bands[-1].append(i)
    bands=[b for b in bands if len(b)>=8]
    assert bands,'No transparent gutter'
    b=min(bands,key=lambda b:abs((b[0]+b[-1])/2-size/2))
    return (b[0]+b[-1])//2
y=gap(h,lambda i:sum(alpha.crop((0,i,w,i+1)).histogram()[16:])==0)
x1=gap(w,lambda i:sum(alpha.crop((i,0,i+1,y)).histogram()[16:])==0)
x2=gap(w,lambda i:sum(alpha.crop((i,y,i+1,h)).histogram()[16:])==0)
rects={'se':[0,0,x1,y],'sw':[x1,0,w-x1,y],'ne':[0,y,x2,h-y],'nw':[x2,y,w-x2,h-y]}
fraction=alpha.histogram()[0]/(w*h)
manifest={'schema':'native_direction4_spriteframes_v1','character':'bound_deng_fei','sources':{'bound':{'path':job['repository_input'],'sha256':job['sha256'],'job':'bound','mode':'RGBA','native_size':[w,h],'import_limit':1536,'imported_size':[w,h],'full_atlas':True,'alpha_zero_fraction':fraction,'unused_regions':[]}},'states':{'idle':['idle']},'poses':{},'resources':[],'scope':'Dedicated unarmed standing bound_deng_fei narrative idle only. Only authored idle; walk/hurt standing fallback, no generic combat or death borrowing. Runtime acceptance requires separate final receipt.'}
checks=[]
for direction,(x,y,rw,rh) in rects.items():
    crop=alpha.crop((x,y,x+rw,y+rh))
    bbox=crop.point(lambda a:255 if a>16 else 0).getbbox()
    assert bbox
    l,t,r,b=bbox;clearance=min(l,t,rw-r,rh-b)
    assert clearance>=4,(direction,clearance)
    virtual=max(rw,rh);padl=(virtual-rw)//2;padt=(virtual-rh)//2
    contact=crop.crop((0,b-int((b-t)*.23),rw,b)).point(lambda a:255 if a>16 else 0).getbbox()
    px=(contact[0]+contact[2])/2
    pivot=[px,b-4]
    manifest['poses']['idle_'+direction]={'source':'bound','region_raw':[x,y,rw,rh],'region':[x,y,rw,rh],'margin':[padl,padt,virtual-rw,virtual-rh],'virtual_size_imported':virtual,'pivot':pivot,'draw_offset_px':[virtual*.5-(padl+pivot[0]),virtual*.82-(padt+pivot[1])],'draw_scale':round(virtual*0.78/(b-t),6)}
    manifest['resources'].append(f'assets/anim/bound_deng_fei_idle_{direction}.tres')
    checks.append({'pose':'idle_'+direction,'bounds':list(bbox),'region':rects[direction],'clearance_px':clearance,'passed':True})
lineage={'schema':'native_direction4_generation_lineage_v1','character':'bound_deng_fei','identity_note':'TOP ROW LEFT CELL (column1 row1) Deng Fei: fierce rugged adult Chinese man with medium tawny skin, intense reddish-brown eyes (natural, no glowing effects), thick curly black mane hair tied with rust-brown strip/top knot, heavy curly full beard and moustache. Brown ragged shoulder cloak/scarf, dark brown leather/lamellar torso armor with brass round face chest ornament and shoulder edging, rust-red waist sash, dark brown trousers and boots. Preserve wild curly beard and brown identity. Remove all iron chains, metal chain loops, balls, weapons and carried items. Front wrist-bound unarmed standing foot captive.','jobs':[{k:j[k] for k in ('key','method','sha256','references','prompt')} | {'repository_path':j['repository_input'],'status':'selected' if j['selected'] else 'required_reference',**({'generation_id':j['generation_id']} if 'generation_id' in j else {})} for j in jobs]}
write(ROOT/'assets/direction4'/f'{TAG}.json',manifest)
lineage['original_reference']={'path':jobs[1]['repository_input'],'sha256':jobs[1]['sha256']}
write(HERE/'generation.json',lineage)
write(ROOT/'qa'/TAG/'bounds_audit.json',{'passed':True,'checks':checks,'native_pixel_edits':False,'scope':'Read-only metadata/alpha clearance. Facing and story behavior require render QA.'})
print(json.dumps({'sources':1,'poses':4,'resources':4,'native_size':[w,h],'bounds':checks},ensure_ascii=False))
