"""Compile native Wu death cutouts into AtlasTexture frames; never edit PNG pixels."""
from pathlib import Path
import argparse,copy,hashlib,json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument('--import-receipt',type=Path);args=ap.parse_args()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
prefix='assets/characters/wu_song_traits_20261006/'
jobs=[('se','a8b1af03-64ea-425d-9d78-ae4e596efdf5'),('sw','66d0a3f3-92db-45bc-9b28-2ecdaf87428c'),('ne','d7537618-57ef-46e4-a452-83010e5d1b16'),('nw','71baba91-17bf-4506-a90c-4c3e26c3defc'),
 ('sw2','292cfb64-4a77-48bd-a7b9-9c708eebbbdc'),('nw2','c2613328-df7e-41c7-9acb-fad1c8d29982'),('ne2','031999c4-e25a-47fb-aed2-2dc069b8b63f'),('sw3','a4ce70e5-2f9f-46f5-abd3-e101392f95e5'),('ne3','31f96161-2ca7-4bf4-a44e-9cdef9b4af7c')]
selected={'se','sw3','ne3','nw2'};sources={};graph=[]
for name,gid in jobs:
 p=ROOT/(prefix+'death_'+name+'_v8.png');request=HERE/('wu_song_death_'+name+'_v8_request.json');q=read(request)
 with Image.open(p) as im:
  assert im.mode=='RGBA';size=list(im.size);box=im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox();assert box
 s={'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'mode':'RGBA','native_size':size,'imported_size':size,'import_dimensions_verified':False,'selected':name in selected,'native_bounds':list(box)}
 if name in selected:sources[name]=s
 refs=[{'path':Path(raw).relative_to(ROOT).as_posix(),'sha256':sha(Path(raw))} for raw in q['referenced_image_paths']]
 graph.append({'key':'death_'+name+'_v8','method':'built_in_imagegen','generation_id':gid,'repository_path':s['path'],'sha256':s['sha256'],'native_size':size,
 'request':request.relative_to(ROOT).as_posix(),'request_sha256':sha(request),'prompt':q['prompt'],'references':refs,'transparent_background':True,'native_pixel_edits':False,
 'selection':'Selected subset only' if name in selected else 'Retained failed ancestor; wrong heading, missing blade or blade cell crossing'})
combat_path=ROOT/'assets/direction4/ordinary_wu_song_20261007_combat_v7.json';combat=read(combat_path)
sources['combat_nw']=copy.deepcopy(combat['sources']['actions_nw3_v7'])
receipt=read(args.import_receipt) if args.import_receipt else None
if receipt:
 assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed'];dims={r['path']:r for r in receipt['dimensions']['checks']}
 for s in sources.values():
  row=dims[s['path']];assert row['passed'] and [row['width'],row['height']]==s['native_size'];s['import_dimensions_verified']=True
seed_source=combat['sources']['actions_ne_v6']['path'];seed_text=(ROOT/(seed_source+'.import')).read_text(encoding='utf-8')
for s in sources.values():
 p=ROOT/s['path'];desc=Path(str(p)+'.import')
 if desc.exists():continue
 old_hash=hashlib.md5(('res://'+seed_source).encode()).hexdigest();new_hash=hashlib.md5(('res://'+s['path']).encode()).hexdigest()
 text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(seed_source,s['path']).replace(Path(seed_source).name+'-'+old_hash,p.name+'-'+new_hash)
 desc.write_bytes(text.encode('utf-8'))
# Extra vertical space takes the complete upper poses; no native bitmap crop,
# rescale/mirror. The actual atlas has a clear inter-row gutter, not equal cells.
regions={'se':[[0,0,627,720],[627,0,627,720],[627,740,627,514]],
 'sw':[[0,0,656,680],[656,0,656,680],[656,700,656,499]],
 'ne':[[0,0,627,720],[627,0,627,720],[627,740,627,514]],
 'nw':[[0,0,627,720],[627,0,627,720],[627,740,627,514]]}
srcs={'se':'se','sw':'sw3','ne':'ne3','nw':'nw2'}
# Independently declared anatomical head and sole windows on recoil. NW first
# generated recoil faces NE and is NOT selected; its adult scale is measured
# only, while the already-qualified NW hurt/recoil supplies the first frame.
windows={'se':[[160,100,310,255],[170,520,280,690],[380,470,515,660]],
 'sw':[[350,60,485,240],[185,450,315,645],[450,470,575,655]],
 'ne':[[165,75,300,260],[170,455,300,650],[340,470,485,690]],
 'nw':[[190,60,335,260],[170,455,310,650],[375,470,525,690]]}
def bounds(mask,window):
 x,y,x2,y2=window;b=mask.crop((x,y,x2,y2)).getbbox();assert b
 return [x+b[0],y+b[1],x+b[2],y+b[3]]
poses={};sampling=[]
for d in ['se','sw','ne','nw']:
 source=srcs[d]
 with Image.open(ROOT/sources[source]['path']) as im:
  mask=im.getchannel('A').point(lambda a:255 if a>16 else 0)
  h,l,r=[bounds(mask,w) for w in windows[d]]
 reference_height=(l[3]+r[3])/2-h[1];assert reference_height>350
 recoil_pivot=[(l[0]+l[2]+r[0]+r[2])/4,(l[3]+r[3])/2-2]
 for i,state in enumerate(['fatal','fall','rest']):
  if d=='nw' and state=='fatal':
   pose=copy.deepcopy(combat['poses']['hurt_nw']);pose['source']='combat_nw';poses[state+'_'+d]=pose;continue
  region=regions[d][i];w,hh=region[2:];size=max(w,hh);pad=[(size-w)/2,(size-hh)/2,size-w,size-hh]
  # Support anchors are metadata fixtures, verified against actual death next.
  if state=='fatal':raw_pivot=recoil_pivot
  elif state=='fall':raw_pivot=[w*.5,hh*.83]
  else:raw_pivot=[w*.5,hh*.61]
  pivot=[raw_pivot[0]+pad[0],raw_pivot[1]+pad[1]]
  pose={'source':source,'region':region,'margin':pad,'virtual_size_imported':size,'pivot':pivot,
   'draw_offset_px':[round(size*.5-pivot[0],6),round(size*.82-pivot[1],6)],'draw_scale':round(size*.78/reference_height,6)}
  poses[state+'_'+d]=pose
 sampling.append({'direction':d,'source':sources[source]['path'],'head':h,'left_sole':l,'right_sole':r,'reference_body_height':reference_height,
  'scope':'Recoil-derived anatomical scale maintained through collapse; corpse height is not stretched to standing height. Support anchors await actual-world visual review.'})
resources=[]
for d in ['se','sw','ne','nw']:
 used=list(dict.fromkeys(poses[n+'_'+d]['source'] for n in ['fatal','fall','rest']))
 lines=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(1+len(used)+3),'']
 for s in used:lines.append('[ext_resource type="Texture2D" path="res://%s" id="%s"]'%(sources[s]['path'],s))
 for n in ['fatal','fall','rest']:
  p=poses[n+'_'+d];lines+=['','[sub_resource type="AtlasTexture" id="%s"]'%n,'atlas = ExtResource("%s")'%p['source'],
    'region = Rect2(%s)'%', '.join(map(str,p['region'])),'margin = Rect2(%s)'%', '.join(map(str,p['margin'])),'filter_clip = true',
    'metadata/draw_offset_px = Vector2(%s, %s)'%tuple(p['draw_offset_px']),'metadata/authored_direction4 = true','metadata/draw_scale = '+str(p['draw_scale'])]
 lines+=['','[resource]','animations = [{','"frames": [',',\n'.join('{"duration": 1.0, "texture": SubResource("%s")}'%n for n in ['fatal','fall','rest','rest']),'],','"loop": false,','"name": &"default",','"speed": 4.0','}]','']
 name='assets/anim/character_traits_v8_wu_song_death_death_'+d+'.tres';(ROOT/name).write_bytes('\n'.join(lines).encode('utf-8'));resources.append(name)
m={'schema':'native_direction4_spriteframes_v1','revision':'character_traits_v5','character':'character_traits_v8_wu_song_death','identity_key':'wu_song','candidate_only':True,'production_qualified':False,
 'runtime_death_qualified':False,'states':{'death':['fatal','fall','rest','rest']},'sources':sources,'poses':poses,'resources':resources,
 'scope':'Native three-pose/four-slot death candidate, actual recoil/fall/rest only. Rest repeated intentionally for terminal hold. Living down route is separate and unmodified. NW recoil uses qualified same-character NW combat hurt; generated NW2 wrong-heading recoil is excluded. Actual fatal damage/death/shadow/release still required.'}
write(ROOT/'assets/direction4/ordinary_wu_song_20261007_death_v8.json',m)
write(ROOT/'qa/zhu_wounded_20261005/wu_death_sampling_v8.json',{'samples':sampling,'native_pixels_edited':False,'resources':resources,'selected_pose_count':12,'runtime_qualified':False,
 'rejected':'SW/NW first sheets have wrong headings; NE first misses blade, NE2 knives cross cell; SW2 fall misses blade; NW2 recoil excluded. SE impact missing blade is not consumed; selected SE final rest has two.'})
lineage=HERE/'generation_wu_song_combat_v7.json'
write(HERE/'generation_wu_song_death_v8.json',{'parent_lineage':lineage.relative_to(ROOT).as_posix(),'parent_sha256':sha(lineage),'jobs':graph,
 'selected_pose_parent':{'manifest':combat_path.relative_to(ROOT).as_posix(),'sha256':sha(combat_path),'pose':'hurt_nw'},'scope':m['scope']})
print(json.dumps({'retained_outputs':len(graph),'selected_sources':len(sources),'poses':len(poses),'resources':len(resources),'import_verified':bool(receipt),'production_qualified':False}))
