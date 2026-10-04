"""Reproduce native mechanical frame metadata; never write or transform PNGs."""
from pathlib import Path
import json,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,o):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
jobs=json.loads((HERE/'jobs.json').read_text(encoding='utf-8'))
original=json.loads((HERE/'original_reference.json').read_text())
manifest={'schema':'native_direction4_spriteframes_v1','character':'siege_cata','family':'mechanical','sources':{},'poses':{},'states':{'idle':['idle'],'walk':['walk_a','walk_b'],'attack':['idle','raise','raise','raise','release','release','recover','idle'],'death':['collapse','wreck','wreck']},'resources':[],'scope':'Four mechanical states with rigid chassis, two wheel phases, real boulder release and shattered wreck. Repeated lift/release slots allocate phase time, not additional painted poses. No human hurt pose; retained original gameplay and generic nonlethal hit handling.'}
lineage={'schema':'native_direction4_generation_lineage_v1','character':'siege_cata','original_reference':original,'identity_note':'Current four-wheel timber catapult, one spoon/lever, grey rock and rear rope winch. Legacy assets remain as provenance; no pixel transforms.','jobs':[]}
def split(alpha):
 w,h=alpha.size
 def gap(size,empty):
  bands=[]
  for i in range(int(size*.32),int(size*.68)):
   if not empty(i):continue
   if not bands or i>bands[-1][-1]+1:bands.append([i])
   else:bands[-1].append(i)
  bands=[b for b in bands if len(b)>=4];assert bands,'No clear alpha gutter'
  b=min(bands,key=lambda b:abs((b[0]+b[-1])/2-size/2));return (b[0]+b[-1])//2
 y=gap(h,lambda i:sum(alpha.crop((0,i,w,i+1)).histogram()[16:])==0)
 x1=gap(w,lambda i:sum(alpha.crop((i,0,i+1,y)).histogram()[16:])==0)
 x2=gap(w,lambda i:sum(alpha.crop((i,y,i+1,h)).histogram()[16:])==0)
 return {'se':[0,0,x1,y],'sw':[x1,0,w-x1,y],'ne':[0,y,x2,h-y],'nw':[x2,y,w-x2,h-y]}
selected={j['key']:j for j in jobs if j['selected']}
idle=Image.open(ROOT/selected['idle']['repository_path']);ia=idle.getchannel('A');ir=split(ia);widths={}
for d,(x,y,w,h) in ir.items():
 box=ia.crop((x,y+int(h*.40),x+w,y+h)).point(lambda a:255 if a>16 else 0).getbbox();assert box
 widths[d]=box[2]-box[0]
bounds=[];mapping={'walk_b_v2':'walk_b','wreck_v2':'wreck'}
for j in jobs:
 entry={k:j[k] for k in ['key','repository_path','sha256','method','prompt','references','review']}
 entry['status']='selected' if j['selected'] else 'required_reference' if j['retained'] else 'rejected_unused'
 if 'generator_artifacts' in j:entry['generator_artifacts']=j['generator_artifacts']
 lineage['jobs'].append(entry)
 if not j['selected']:continue
 path=j['repository_path'];p=ROOT/path;assert sha(p)==j['sha256']
 im=Image.open(p);assert im.mode=='RGBA' and max(im.size)<=1536
 a=im.getchannel('A');fraction=a.histogram()[0]/(im.width*im.height);assert fraction>.35
 manifest['sources'][j['key']]={'path':path,'sha256':j['sha256'],'job':j['key'],'mode':'RGBA','native_size':list(im.size),'import_limit':1536,'imported_size':list(im.size),'full_atlas':True,'alpha_zero_fraction':fraction,'unused_regions':[]}
 for d,(x,y,w,h) in split(a).items():
  alpha=a.crop((x,y,x+w,y+h));box=alpha.point(lambda a:255 if a>16 else 0).getbbox();assert box
  l,t,r,b=box;clearance=min(l,t,w-r,h-b);assert clearance>=4,(j['key'],d,box)
  virtual=max(w,h);padl=(virtual-w)//2;padt=(virtual-h)//2
  # A lever becoming vertical must not shrink the chassis. All phases use
  # the idle footprint width, with a native canvas-density compensation.
  scale=virtual*.96/(widths[d]*im.width/idle.width)
  contact=alpha.crop((0,b-max(12,int((b-t)*.18)),w,b)).point(lambda a:255 if a>16 else 0).getbbox();assert contact
  px=(contact[0]+contact[2])/2;pivot=[px,b-5]
  key=mapping.get(j['key'],j['key'])+'_'+d
  manifest['poses'][key]={'source':j['key'],'region_raw':[x,y,w,h],'region':[x,y,w,h],'margin':[padl,padt,virtual-w,virtual-h],'virtual_size_imported':virtual,'pivot':pivot,'draw_offset_px':[virtual*.5-(padl+pivot[0]),virtual*.82-(padt+pivot[1])],'draw_scale':round(scale,6)}
  bounds.append({'pose':key,'bbox':list(box),'clearance_px':clearance,'idle_footprint_width_px':widths[d],'passed':True})
for d in ['se','sw','ne','nw']:
 for state in manifest['states']:manifest['resources'].append(f'assets/anim/siege_cata_{state}_{d}.tres')
assert len(manifest['poses'])==32 and len(manifest['resources'])==16
write(ROOT/'assets/direction4/siege_cata_20261004.json',manifest);write(HERE/'generation.json',lineage)
write(ROOT/'qa/siege_cata_direction4_20261004/bounds_audit.json',{'passed':True,'checks':bounds,'scope':'Read-only alpha, gutter and rigid footprint metadata; final motion/facing/ground contacts require native renders.'})
print(json.dumps({'production_sources':8,'independent_sampling_regions':32,'mechanical_resources':16,'pixels_preserved':True}))
