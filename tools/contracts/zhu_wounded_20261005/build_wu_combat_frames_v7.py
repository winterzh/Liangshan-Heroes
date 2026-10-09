"""Author native AtlasTexture metadata and real Wu combat SpriteFrames; no PNG edits."""
from pathlib import Path
import argparse,copy,hashlib,json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--import-receipt',type=Path);args=ap.parse_args()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
parent_path=ROOT/'assets/direction4/ordinary_wu_song_20261007_actions_v6.json';parent=read(parent_path)
gait_path=ROOT/'assets/direction4/ordinary_wu_song_20261006_gait_v5.json';gait=read(gait_path)
lineage_path=HERE/'generation_wu_song_actions_v6.json';lineage=read(lineage_path)
manifest=copy.deepcopy(parent);manifest.update(schema='native_direction4_spriteframes_v1',character='character_traits_v7_wu_song_combat',
 runtime_action_qualified=False,production_qualified=False,continuous_gait_qualified=False,revision='character_traits_v5',
 states={'attack':['windup','windup','strike','strike','recovery','idle'],'hurt':['hurt']},
 scope='Native combat candidate frames including matched existing gait idle recovery. Metadata-only sampling. Exact physical actions, continuous body/weapon transitions, cast/death and production qualification remain required.')
manifest['sources']={k:copy.deepcopy(parent['sources'][k]) for k in ['actions_se_v6','actions_sw2_v6','actions_ne_v6','hurt_sw_v6']}
manifest['sources']['idle']=copy.deepcopy(gait['sources']['idle'])
path='assets/characters/wu_song_traits_20261006/actions_nw3_v7.png';p=ROOT/path
with Image.open(p) as im:
 assert im.mode=='RGBA' and im.size==(1254,1254)
 mask=im.getchannel('A').point(lambda a:255 if a>16 else 0);box=mask.getbbox();assert box and min(box[0],box[1],1254-box[2],1254-box[3])>=4
manifest['sources']['actions_nw3_v7']={'path':path,'sha256':sha(p),'native_size':[1254,1254],'imported_size':[1254,1254],'mode':'RGBA','selected':True,
 'selection':'all four northwest phases, explicit both-boot support correction','import_dimensions_verified':False,'native_alpha_bounds':list(box)}
desc=Path(str(p)+'.import')
if not desc.exists():
 old=manifest['sources']['actions_ne_v6']['path'];seed=(ROOT/(old+'.import')).read_text(encoding='utf-8')
 seed=re.sub(r'^uid=.*\n','',seed,flags=re.M).replace(old,path).replace(Path(old).name+'-'+hashlib.md5(('res://'+old).encode()).hexdigest(),p.name+'-'+hashlib.md5(('res://'+path).encode()).hexdigest())
 desc.write_bytes(seed.encode('utf-8'))
if args.import_receipt:
 receipt=read(args.import_receipt);assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed']
 dims={r['path']:r for r in receipt['dimensions']['checks']}
 for source in manifest['sources'].values():
  c=dims[source['path']];assert c['passed'] and [c['width'],c['height']]==source['native_size']
  assert any(r['path']==source['path'] and r['before_sha256']==source['sha256']==r['after_sha256'] for r in receipt['source_files'])
  source['import_dimensions_verified']=True
# Read-only anatomical windows in local cells. Exclude sabres and robe tails.
# Both boots measured separately: averaging their physical bottom anchors avoids
# raising the body around whichever weapon reaches the lowest alpha row.
windows={
 'se':[
  ([285,95,390,230],[105,450,260,625],[400,450,560,625]),
  ([215,110,370,265],[20,430,170,620],[330,440,530,625]),
  ([250,10,380,210],[120,410,260,625],[325,375,530,590]),
  ([205,30,350,225],[100,425,270,627],[335,385,555,590])],
 'sw':[
  ([180,80,320,250],[90,435,280,620],[420,450,610,627]),
  ([220,110,380,265],[95,435,280,627],[390,390,615,610]),
  ([200,15,340,205],[115,420,285,610],[345,415,535,627]),
  ([575,140,835,415],[310,885,595,1120],[835,950,1100,1220])],
 'ne':[
  ([245,90,385,245],[120,410,290,627],[355,435,550,627]),
  ([225,115,355,265],[40,410,230,627],[295,350,490,610]),
  ([250,15,390,205],[170,400,325,627],[345,400,545,627]),
  ([230,30,365,235],[155,390,305,627],[335,390,535,627])],
 'nw':[
  ([245,95,385,260],[135,450,310,627],[390,430,550,620]),
  ([225,125,385,280],[165,425,355,627],[450,430,620,620]),
  ([250,15,385,215],[135,425,305,627],[350,420,545,627]),
  ([295,40,450,250],[140,430,330,627],[325,400,530,620])]
}
def measure(mask,window,origin):
 x,y,w,h=window[0],window[1],window[2]-window[0],window[3]-window[1]
 roi=mask.crop((origin[0]+x,origin[1]+y,origin[0]+x+w,origin[1]+y+h));b=roi.getbbox();assert b
 # Last six native alpha rows locate the sole rather than the shin/cloth.
 bottom=b[3];sole=roi.crop((0,max(0,bottom-6),w,bottom)).getbbox();assert sole
 return {'window':window,'bounds':[x+b[0],y+b[1],x+b[2],y+b[3]],'sole_anchor':[x+(sole[0]+sole[2])/2,y+bottom-2]}
poses={};proof=[]
for direction,source_key in [('se','actions_se_v6'),('sw','actions_sw2_v6'),('ne','actions_ne_v6'),('nw','actions_nw3_v7')]:
 for i,state in enumerate(['windup','strike','recovery','hurt']):
  source='hurt_sw_v6' if direction=='sw' and state=='hurt' else source_key
  region=[0,0,1254,1254] if source=='hurt_sw_v6' else [[0,0,627,627],[627,0,627,627],[0,627,627,627],[627,627,627,627]][i]
  s=manifest['sources'][source];assert sha(ROOT/s['path'])==s['sha256']
  with Image.open(ROOT/s['path']) as im:
   alpha=im.getchannel('A').point(lambda a:255 if a>16 else 0)
   head,left,right=windows[direction][i];origin=region[:2]
   h=measure(alpha,head,origin);a=measure(alpha,left,origin);b=measure(alpha,right,origin)
  pivot=[(a['sole_anchor'][0]+b['sole_anchor'][0])/2,(a['sole_anchor'][1]+b['sole_anchor'][1])/2]
  height=pivot[1]-h['bounds'][1];assert height>250
  # Attack naturally lowers the center of mass; do not stretch that crouch into
  # upright idle. This is a first metadata candidate, verified in the renderer next.
  target=.73 if state=='strike' else .78
  size=region[2];scale=round(size*target/height,6)
  pose={'source':source,'region':region,'margin':[0,0,0,0],'virtual_size_imported':size,'pivot':pivot,
   'draw_offset_px':[round(size*.5-pivot[0],6),round(size*.82-pivot[1],6)],'draw_scale':scale,
   'sampling_qualified':False,'ground_pivot_status':'Independent boot/head ROI metadata; actual body/weapon/foot transitions not yet qualified'}
  poses[state+'_'+direction]=pose
  proof.append({'pose':state+'_'+direction,'source':s['path'],'head':h,'left_boot':a,'right_boot':b,'pivot':pivot,'head_to_ground':height,'target_drawn_body_height_fraction':target})
 poses['idle_'+direction]=copy.deepcopy(gait['poses']['idle_'+direction])
manifest['poses']=poses;resources=[]
for direction in ['se','sw','ne','nw']:
 for state,order in manifest['states'].items():
  needed=list(dict.fromkeys(order));used=list(dict.fromkeys(poses[n+'_'+direction]['source'] for n in needed))
  lines=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(1+len(used)+len(needed)),'']
  for source in used:lines.append('[ext_resource type="Texture2D" path="res://%s" id="%s"]'%(manifest['sources'][source]['path'],source))
  for name in needed:
   pose=poses[name+'_'+direction];r=pose['region'];m=pose['margin'];o=pose['draw_offset_px']
   lines+=['','[sub_resource type="AtlasTexture" id="%s"]'%name,'atlas = ExtResource("%s")'%pose['source'],
    'region = Rect2(%s)'%', '.join(map(str,r)),'margin = Rect2(%s)'%', '.join(map(str,m)),
    'filter_clip = true','metadata/draw_offset_px = Vector2(%s, %s)'%(o[0],o[1]),'metadata/authored_direction4 = true','metadata/draw_scale = '+str(pose['draw_scale'])]
  lines+=['','[resource]','animations = [{','"frames": [',',\n'.join('{"duration": 1.0, "texture": SubResource("%s")}'%name for name in order),'],','"loop": false,','"name": &"default",','"speed": 4.0','}]','']
  resource='assets/anim/%s_%s_%s.tres'%(manifest['character'],state,direction)
  (ROOT/resource).write_bytes('\n'.join(lines).encode('utf-8'));resources.append(resource)
manifest['resources']=resources
write(ROOT/'assets/direction4/ordinary_wu_song_20261007_combat_v7.json',manifest)
write(ROOT/'qa/zhu_wounded_20261005/wu_combat_sampling_v7.json',{'parent_manifest':str(parent_path.relative_to(ROOT)),'parent_sha256':sha(parent_path),
 'gait_manifest':str(gait_path.relative_to(ROOT)),'gait_sha256':sha(gait_path),'samples':proof,'resources':resources,'scope':'Metadata authoring only. No native pixel edit; boots and head measured independently. Actual runtime transitions remain required.','production_qualified':False})
request=HERE/'wu_song_actions_nw3_v7_request.json'
write(HERE/'generation_wu_song_combat_v7.json',{'parent_lineage':lineage_path.relative_to(ROOT).as_posix(),'parent_sha256':sha(lineage_path),
 'jobs':[{'key':'actions_nw3_v7','method':'built_in_imagegen','generation_id':'af662e8e-cb4c-4a2a-b1f8-f65485ec2b8e','repository_path':path,'sha256':sha(p),
 'request':request.relative_to(ROOT).as_posix(),'request_sha256':sha(request),'prompt':read(request)['prompt'],
 'references':[{'path':parent['sources']['actions_nw2_v6']['path'],'sha256':parent['sources']['actions_nw2_v6']['sha256']}],'native_pixel_edits':False,'transparent_background':True,'selected':True}],
 'scope':'Native northwest supporting-leg fix; earlier immutable action/gait parents retained.'})
print(json.dumps({'sources':len(manifest['sources']),'poses':len(poses),'resources':len(resources),'native_import_verified':bool(args.import_receipt),'runtime_qualified':False}))
