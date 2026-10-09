"""Reproduce native Hook-spear infantry lineage and frame metadata; never edit PNG pixels."""
from pathlib import Path
import json,hashlib,re,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
ASSET='assets/characters/gou_lian_direction4_20261004'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,o):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
jobs=json.loads((HERE/'jobs.json').read_text(encoding='utf-8'))
selection=json.loads((HERE/'selection.json').read_text(encoding='utf-8'))
lineage={'schema':'native_direction4_generation_lineage_v1','character':'gou_lian','original_reference':{'path':'assets/portraits8.png','sha256':sha(ROOT/'assets/portraits8.png')},'identity_note':'Middle-right current standard portrait: plain iron helmet, grey neck flap and folded collar, short moustache/goatee, brown quilted tunic. One hooked spear, left hand forward and right rear; ordinary non-hero foot infantry with exact spear timing and anti-cavalry bonus retained. Legacy blue body is camera/style only.','jobs':[]}
manifest={'schema':'native_direction4_spriteframes_v1','character':'gou_lian','sources':{},'poses':{},'states':{'idle':['idle'],'walk':['walk_a','walk_b'],'attack':['windup','strike','idle'],'hurt':['hurt'],'death':['fall','terminal','terminal']},'resources':[],'scope':'32 independent low-frame ordinary hook-spear foot infantry poses; current portrait atlas cell, HP105/ATK11/CD1.1/range30/speed68/bonus_cav3.5 and exact spear timing retained.'}
def split(alpha):
 w,h=alpha.size
 def gap(size,empty):
  values=[i for i in range(int(size*.32),int(size*.68)) if empty(i)]
  assert values,'No empty-alpha inter-cell gutter'
  bands=[]
  for i in values:
   if not bands or i>bands[-1][-1]+1:bands.append([i])
   else:bands[-1].append(i)
  bands=[b for b in bands if len(b)>=8];assert bands
  b=min(bands,key=lambda b:abs((b[0]+b[-1])/2-size/2))
  return (b[0]+b[-1])//2
 y=gap(h,lambda i:sum(alpha.crop((0,i,w,i+1)).histogram()[16:])==0)
 x1=gap(w,lambda i:sum(alpha.crop((i,0,i+1,y)).histogram()[16:])==0)
 x2=gap(w,lambda i:sum(alpha.crop((i,y,i+1,h)).histogram()[16:])==0)
 return {'se':[0,0,x1,y],'sw':[x1,0,w-x1,y],'ne':[0,y,x2,h-y],'nw':[x2,y,w-x2,h-y]}
bounds=[]
for j in jobs:
 retained=j['retained'];path=j['repository_input']
 if retained:
  target=ROOT/path
  if not target.exists():target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(j['native_path'],target)
  assert sha(target)==j['sha256'],j['key']+' native bytes changed'
 entry={'key':j['key'],'repository_path':path,'sha256':j['sha256'],'method':j.get('method','built_in_imagegen'),'prompt':j['prompt'],'references':j['references'],'status':'selected' if j['selected'] else 'required_reference' if retained else 'rejected_unused'}
 for field in ['generation_id','generator_artifacts']:
  if field in j:entry[field]=j[field]
 lineage['jobs'].append(entry)
 if not j['selected']:continue
 im=Image.open(target);assert im.mode=='RGBA' and max(im.size)<=1536
 alpha=im.getchannel('A');fraction=alpha.histogram()[0]/(im.width*im.height);assert fraction>.35
 poses=[p for p,k in selection.items() if k==j['key']]
 atlas=bool(j.get('atlas',False))
 rects=split(alpha) if atlas else {poses[0].rsplit('_',1)[-1]:[0,0,im.width,im.height]}
 used={p.rsplit('_',1)[-1] for p in poses}
 manifest['sources'][j['key']]={'path':path,'sha256':j['sha256'],'job':j['key'],'mode':'RGBA','native_size':list(im.size),'import_limit':1536,'imported_size':list(im.size),'full_atlas':True,'alpha_zero_fraction':fraction,'unused_regions':[{'region':rect,'reason':'Rejected facing, handedness or gait candidate; separately authored replacement selected.'} for d,rect in rects.items() if d not in used]}
 descriptor=Path(str(target)+'.import')
 if not descriptor.exists():
  res='res://'+path;cache='res://.godot/imported/'+target.name+'-'+hashlib.md5(res.encode()).hexdigest()+'.ctex'
  template=(ROOT/'assets/characters/guan_zhanzi_direction4_20260915/ne_fall.png.import').read_text()
  template=re.sub(r'uid="[^"]*"\n','',template);template=re.sub(r'res://\.godot/imported/[^"]+',cache,template)
  template=re.sub(r'source_file="[^"]*"','source_file="'+res+'"',template);template=re.sub(r'process/size_limit=\d+','process/size_limit=1536',template)
  descriptor.write_text(template,encoding='utf-8',newline='\n')
 for p in poses:
  pose,d=p.rsplit('_',1);x,y,w,h=rects[d]
  bbox=alpha.crop((x,y,x+w,y+h)).point(lambda a:255 if a>16 else 0).getbbox();assert bbox
  l,t,r,b=bbox;clearance=min(l,t,w-r,h-b);assert clearance>=4,(p,bbox,rects[d])
  virtual=max(w,h);padl=(virtual-w)//2;padt=(virtual-h)//2
  desired={'idle':.78,'walk_a':.78,'walk_b':.78,'windup':.78,'strike':.78,'hurt':.78,'fall':.56,'terminal':.82}[pose]
  scale=virtual*desired/((r-l) if pose=='terminal' else b-t)
  # Standing contact x uses the lower boot silhouette, not a sideways blade.
  contact=alpha.crop((x,y+max(t,b-int((b-t)*.23)),x+w,y+b)).point(lambda a:255 if a>16 else 0).getbbox()
  px=(contact[0]+contact[2])/2 if contact and pose not in ['fall','terminal'] else (l+r)/2
  pivot=[px,b-7]
  # Overrides describe body contact/height; never modify native PNG pixels.
  overrides=json.loads((HERE/'anchors.json').read_text(encoding='utf-8'))
  override=overrides.get(p,{})
  if 'body_top' in override:scale=virtual*desired/(override.get('body_bottom',b)-override['body_top'])
  if 'pivot' in override:pivot=override['pivot']
  if 'desired' in override:scale=virtual*override['desired']/(override.get('body_bottom',b)-override.get('body_top',t))
  manifest['poses'][p]={'source':j['key'],'region_raw':[x,y,w,h],'region':[x,y,w,h],'margin':[padl,padt,virtual-w,virtual-h],'virtual_size_imported':virtual,'pivot':pivot,'draw_offset_px':[virtual*.5-(padl+pivot[0]),virtual*.82-(padt+pivot[1])],'draw_scale':round(scale,6)}
  bounds.append({'pose':p,'bbox':list(bbox),'clearance_px':clearance,'single_canvas':not atlas,'passed':True})
for d in ['se','sw','ne','nw']:
 for state in manifest['states']:manifest['resources'].append(f'assets/anim/gou_lian_{state}_{d}.tres')
assert len(manifest['poses'])==32
write(ROOT/'assets/direction4/gou_lian_20261004.json',manifest);write(HERE/'generation.json',lineage)
write(ROOT/'qa/gou_lian_direction4_20261004/bounds_audit.json',{'passed':True,'checks':bounds,'scope':'Read-only alpha margins and metadata; actual facing, hand identity and anchors require native visual review.'})
print(json.dumps({'production_pngs':len(manifest['sources']),'independent_poses':32,'native_bytes_preserved':True}))
