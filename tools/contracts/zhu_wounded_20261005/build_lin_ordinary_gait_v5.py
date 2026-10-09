"""Author Lin gait resources with boot-only pivots and complete native ancestry."""
from pathlib import Path
import argparse,copy,hashlib,json,re
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--import-receipt',type=Path);args=ap.parse_args()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
original=read(ROOT/'assets/direction4/ordinary_lin_chong_20261006_traits_v4.json')
lineage=read(HERE/'generation_lin_chong_v4.json');graph={j['key']:copy.deepcopy(j) for j in lineage['jobs']}
wu=read(HERE/'generation_wu_song_gait_v5.json');wu_ref='retained_wu_gait_original_v5'
graph[wu_ref]={'key':wu_ref,'method':'retained_identity_reference','generation_id':None,
 'repository_path':wu['original_reference']['path'],'sha256':wu['original_reference']['sha256'],
 'baseline_commit':'27f45b245e2b39f1f779fbfa62772e14bb68dd56','reference_role':'Retained original ancestry for human leg/camera references only; no Lin identity inherited',
 'references':[],'selected':False,'native_pixel_edits':False}
for j in wu['jobs']:
 if j['key'] in graph:assert graph[j['key']]['sha256']==j['sha256'];continue
 row=copy.deepcopy(j);row['references']=[wu_ref if k=='original' else k for k in row['references']];row['selected']=False;graph[row['key']]=row
known={j['repository_path']:j['key'] for j in graph.values() if j['repository_path']}
def ancestor(path):
 if path in known:return known[path]
 p=ROOT/path;jp=HERE/'jobs'/('lin_chong_'+p.stem+'.json');j=read(jp)
 assert j['output']==path and j['output_sha256']==sha(p)
 req=ROOT/j['request'];assert sha(req)==j['request_sha256'];request=read(req)
 refs=[]
 for ref in j['references']:assert sha(ROOT/ref['path'])==ref['sha256'];refs.append(ancestor(ref['path']))
 key=jp.stem;graph[key]={'key':key,'method':'built_in_imagegen','generation_id':j['generation_id'],
  'repository_path':path,'sha256':sha(p),'prompt':request['prompt'],'request':j['request'],'request_sha256':sha(req),
  'references':refs,'transparent_background':True,'selected':True,'native_pixel_edits':False}
 known[path]=key;return key
receipt=read(args.import_receipt) if args.import_receipt else None
dimensions={c['path']:c for c in receipt['dimensions']['checks']} if receipt else {}
if receipt:assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed']
m=copy.deepcopy(original);m.update(character='character_traits_v5_lin_chong_gait',identity_key='lin_chong',revision='character_traits_v5',candidate_only=True,continuous_gait_qualified=False)
m['states']={'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']}
m['resources']=[f"assets/anim/{m['character']}_{s}_{d}.tres" for s in ['idle','walk'] for d in ['se','sw','ne','nw']]
m['scope']='Ordinary armed Lin Chong upright idle/four-heading four-phase gait candidate; boot-only pivots exclude spear. Continuous/full-game action qualification remains open.'
seed_text=(ROOT/(m['sources']['idle']['path']+'.import')).read_text(encoding='utf-8');sampling=[]
# Authored anatomical boot windows, not image edits. Avoid spear/tassel foreground.
idle_windows={'se':[260,455,550,610],'sw':[790,455,1120,610],'ne':[105,1060,400,1215],'nw':[750,1060,1040,1215]}
def foot_geometry(mask,box,window,origin=(0,0),virtual=1254):
 x0,y0,x1,y1=window;feet=mask.crop((x0,y0,x1,y1)).getbbox();assert feet
 bounds=[x0+feet[0],y0+feet[1],x0+feet[2],y0+feet[3]]
 pivot=[(bounds[0]+bounds[2])/2-origin[0],bounds[3]-4-origin[1]]
 body_height=bounds[3]-box[1];assert body_height>virtual*.45
 return pivot,round(virtual*.78/body_height,6),bounds
with Image.open(ROOT/m['sources']['idle']['path']) as im:
 mask=im.getchannel('A').point(lambda v:255 if v>16 else 0)
 for d in ['se','sw','ne','nw']:
  pose=m['poses']['idle_'+d];x,y,w,h=pose['region_raw'];b=mask.crop((x,y,x+w,y+h)).getbbox();assert b
  box=[x+b[0],y+b[1],x+b[2],y+b[3]]
  pivot,scale,boots=foot_geometry(mask,box,idle_windows[d],(x,y),pose['virtual_size_imported'])
  pose.update(pivot=pivot,draw_offset_px=[pose['virtual_size_imported']*.5-pivot[0],pose['virtual_size_imported']*.82-pivot[1]],draw_scale=scale)
  sampling.append({'pose':'idle_'+d,'boot_window':idle_windows[d],'boot_bounds':boots,'pivot':pivot,'notes':'Boot-only authoring; original v4 resources untouched'})
selection={'walk_b_se':'walk_b_se2','walk_b_sw':'walk_b_sw4','walk_a_ne':'walk_a_ne3','walk_b_nw':'walk_b_nw3'}
for s in ['walk_a','passing_a','walk_b','passing_b']:
 for d in ['se','sw','ne','nw']:
  state=s+'_'+d;variant=state+'2' if s.startswith('passing') else selection.get(state,state)
  path=f'assets/characters/lin_chong_traits_20261006/{variant}_v5.png';p=ROOT/path;job=ancestor(path)
  with Image.open(p) as im:
   assert im.mode=='RGBA' and im.size==(1254,1254)
   alpha=im.getchannel('A');mask=alpha.point(lambda v:255 if v>16 else 0);box=mask.getbbox();assert box
   assert min(box[0],box[1],1254-box[2],1254-box[3])>=4
   lower=box[3]-int((box[3]-box[1])*.19)
   window=[410,lower,960,1254] if d in ['se','sw'] else [320,lower,910,1254]
   pivot,scale,boots=foot_geometry(mask,box,window)
   zero=alpha.histogram()[0]/(1254*1254)
  verified=False
  if receipt:
   v=dimensions[path];assert v['passed'] and [v['width'],v['height']]==[1254,1254]
   assert any(v['path']==path and v['before_sha256']==v['after_sha256']==sha(p) for v in receipt['source_files']);verified=True
  m['sources'][state]={'path':path,'sha256':sha(p),'job':job,'mode':'RGBA','native_size':[1254,1254],'imported_size':[1254,1254],
   'import_limit':1536,'import_dimensions_verified':verified,'import_dimension_status':'independently verified native dimensions' if verified else 'expected pending independent Godot import','full_atlas':True,'alpha_zero_fraction':zero}
  m['poses'][state]={'source':state,'region_raw':[0,0,1254,1254],'region':[0,0,1254,1254],'margin':[0,0,0,0],'virtual_size_imported':1254,
   'pivot':pivot,'draw_offset_px':[627-pivot[0],1254*.82-pivot[1]],'draw_scale':scale}
  sampling.append({'pose':state,'source':path,'bounds':list(box),'boot_window':window,'boot_bounds':boots,'pivot':pivot,
   'notes':'Read-only boot window excludes spear; initial authoring, not planted-foot/continuous-motion qualification'})
  desc=Path(str(p)+'.import')
  if not desc.exists():
   old=m['sources']['idle']['path'];a=hashlib.md5(('res://'+old).encode()).hexdigest();b=hashlib.md5(('res://'+path).encode()).hexdigest()
   text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(old,path).replace(Path(old).name+'-'+a,p.name+'-'+b);desc.write_bytes(text.encode('utf-8'))
used={v['job'] for v in m['sources'].values()}
for j in graph.values():j['selected']=j['key'] in used
write(ROOT/'assets/direction4/ordinary_lin_chong_20261006_gait_v5.json',m)
write(HERE/'generation_lin_chong_gait_v5.json',{'original_reference':lineage['original_reference'],'jobs':list(graph.values()),
 'scope':'Native Lin identity ancestry plus explicitly human leg/camera-only Wu references, math producers and failed parents; no cross-character production frames'})
write(ROOT/'qa/zhu_wounded_20261005/lin_chong_gait_sampling_v5.json',{'selection':sampling,'native_sources':17,'poses':20,'native_pixel_edits':False,'production_qualified':False})
print(json.dumps({'sources':len(m['sources']),'poses':len(m['poses']),'resources':len(m['resources']),'import_verified':bool(receipt),'boot_only_pivots':True,'production_qualified':False}))
