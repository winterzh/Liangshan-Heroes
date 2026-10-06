"""Record native Wu action candidates and lineage. No raster edits or production route."""
from pathlib import Path
import argparse, hashlib, json, re
from PIL import Image
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--import-receipt',type=Path);args=ap.parse_args()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
prefix='assets/characters/wu_song_traits_20261006/'
jobs=[
 ('actions_se_v6','wu_song_actions_se_v6','4d633337-1f4a-45b2-be30-a45d2894af9e','all four southeast phases',True),
 ('actions_sw_v6','wu_song_actions_sw_v6','c16f331b-5a21-4171-b902-26c31373cf47','rejected: windup and hurt face southeast',False),
 ('actions_ne_v6','wu_song_actions_ne_v6','08863ea7-9c8e-4381-91e8-dc0398197e0e','all four northeast rear phases',True),
 ('actions_nw_v6','wu_song_actions_nw_v6','0d48ac28-57e2-483a-a95c-bf830397a43d','rejected: strike rear boot crosses equal top-row cell boundary',False),
 ('actions_sw2_v6','wu_song_actions_sw2_v6','c5259b1a-225c-4a5b-a887-2ff9b6204ff6','ONLY windup/strike/recovery selected; hurt still faces southeast',True),
 ('actions_nw2_v6','wu_song_actions_nw2_v6','7439b95d-3e24-44fe-8c08-c03e90a4ce3c','all four northwest rear phases; strike supporting-leg/foot anatomy still requires runtime review',True),
 ('hurt_sw_v6','wu_song_hurt_sw_v6','318d494f-4119-4267-b8e4-c9b248cdfaaa','single southwest hurt selected',True),
]
receipt=read(args.import_receipt) if args.import_receipt else None
if receipt:assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed']
dimensions={r['path']:r for r in receipt['dimensions']['checks']} if receipt else {}
sources={};graph=[];seed=ROOT/(prefix+'walk_a_se_v5.png.import');seed_text=seed.read_text(encoding='utf-8')
for name,request_name,generation_id,selection,selected in jobs:
 path=prefix+name+'.png';p=ROOT/path;request_path=HERE/(request_name+'_request.json');request=read(request_path)
 original=Path('C:/Users/Administrator/.codex/generated_images/01a1009d-487a-7213-8be1-dacfb17540a0')/('exec-'+generation_id+'.png')
 assert sha(p)==sha(original) and request['transparent_background']
 with Image.open(p) as im:
  assert im.mode=='RGBA' and im.size==(1254,1254)
  alpha=im.getchannel('A');bounds=alpha.point(lambda a:255 if a>16 else 0).getbbox()
  assert bounds and min(bounds[0],bounds[1],im.width-bounds[2],im.height-bounds[3])>=4
  zero_fraction=alpha.histogram()[0]/(im.width*im.height)
 if receipt:
  assert dimensions[path]['passed'] and [dimensions[path]['width'],dimensions[path]['height']]==[1254,1254]
  assert any(r['path']==path and r['before_sha256']==sha(p)==r['after_sha256'] for r in receipt['source_files'])
 sources[name]={'path':path,'sha256':sha(p),'native_size':[1254,1254],'mode':'RGBA','selected':selected,'selection':selection,
  'imported_size':[1254,1254],'import_dimensions_verified':bool(receipt),'alpha_zero_fraction':zero_fraction,'native_alpha_bounds':list(bounds)}
 refs=[]
 for raw in request['referenced_image_paths']:
  parent=Path(raw);assert parent.resolve().is_relative_to(ROOT)
  refs.append({'path':parent.relative_to(ROOT).as_posix(),'sha256':sha(parent)})
 graph.append({'key':name,'method':'built_in_imagegen','generation_id':generation_id,'repository_path':path,'sha256':sha(p),
  'request':request_path.relative_to(ROOT).as_posix(),'request_sha256':sha(request_path),'prompt':request['prompt'],
  'references':refs,'transparent_background':True,'native_pixel_edits':False,'selection':selection,'selected':selected})
 desc=Path(str(p)+'.import')
 if not desc.exists():
  old_path=prefix+'walk_a_se_v5.png';old_md5=hashlib.md5(('res://'+old_path).encode()).hexdigest();new_md5=hashlib.md5(('res://'+path).encode()).hexdigest()
  text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(old_path,path).replace(Path(old_path).name+'-'+old_md5,p.name+'-'+new_md5)
  desc.write_bytes(text.encode('utf-8'))
poses={}
for direction,source in [('se','actions_se_v6'),('sw','actions_sw2_v6'),('ne','actions_ne_v6'),('nw','actions_nw2_v6')]:
 for state,region in [('windup',[0,0,627,627]),('strike',[627,0,627,627]),('recovery',[0,627,627,627]),('hurt',[627,627,627,627])]:
  poses[state+'_'+direction]={'source':'hurt_sw_v6' if direction=='sw' and state=='hurt' else source,
    'region':[0,0,1254,1254] if direction=='sw' and state=='hurt' else region,
    'sampling_qualified':False,'ground_pivot_status':'not authored; independent boot/head measurements and actual runtime matching remain required'}
manifest={'schema':'native_action_source_candidates_v1','identity_key':'wu_song','character':'character_traits_v6_wu_song_actions','revision':'character_traits_v5',
 'candidate_only':True,'production_qualified':False,'runtime_action_qualified':False,'sources':sources,'poses':poses,'resources':[],
 'scope':'Seven retained native source PNGs including failures; selected five sources supply sixteen direction/action pose candidates. No authored ground sampling, SpriteFrames or production route yet. Not cast/death/full-family/continuous gait or chapter qualification.'}
write(ROOT/'assets/direction4/ordinary_wu_song_20261007_actions_v6.json',manifest)
parent=HERE/'generation_wu_song_gait_v5.json'
write(HERE/'generation_wu_song_actions_v6.json',{'parent_lineage':parent.relative_to(ROOT).as_posix(),'parent_sha256':sha(parent),
 'original_attack_reference':{'path':'assets/anim/wu_song_attack.png','sha256':sha(ROOT/'assets/anim/wu_song_attack.png')},'jobs':graph,
 'scope':'Exact requests, native outputs and parents retained. Direct static source selection only; no production or runtime action qualification.'})
print(json.dumps({'native_sources':7,'selected_sources':5,'poses':len(poses),'import_verified':bool(receipt),'resources':0,'production_qualified':False}))
