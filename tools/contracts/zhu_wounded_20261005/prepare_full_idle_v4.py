"""Build full-canvas four-direction idle candidates without editing PNG pixels."""
from pathlib import Path
import argparse,hashlib,json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
DIRS=('se','sw','ne','nw')
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('character',choices=('wang_ying',))
parser.add_argument('--import-receipt',type=Path)
args=parser.parse_args();key=args.character
lineage=read(HERE/f'generation_{key}_v4.json')
assert sha(ROOT/lineage['original_reference']['path'])==lineage['original_reference']['sha256']
graph={j['key']:{**j,'selected':False} for j in lineage['jobs']}
by_path={j['repository_path']:j['key'] for j in graph.values()}
receipt=read(args.import_receipt) if args.import_receipt else None
dimensions={}
if receipt:
    assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed']
    dimensions={c['path']:c for c in receipt['dimensions']['checks']}
sources={};poses={};bounds=[]
seed=f'assets/characters/{key}_wounded_20261005/idle_spacing_v3.png'
seed_text=Path(str(ROOT/seed)+'.import').read_text(encoding='utf-8')
for d in DIRS:
    jp=HERE/f'jobs/{key}_idle_single_{d}_v4.json';job=read(jp)
    path=job['output'];p=ROOT/path
    assert sha(p)==job['output_sha256'] and not job['native_pixel_edits']
    request=read(ROOT/job['request']);assert sha(ROOT/job['request'])==job['request_sha256']
    refs=[]
    for parent in job['references']:
        assert sha(ROOT/parent['path'])==parent['sha256'] and parent['path'] in by_path
        refs.append(by_path[parent['path']])
    assert len(refs)==len(request['referenced_image_paths'])==1 and request['transparent_background']
    recorded=request['referenced_image_paths'][0].replace('\\','/').lower()
    assert recorded.endswith('/'+job['references'][0]['path'].lower())
    graph[jp.stem]={'key':jp.stem,'method':'built_in_imagegen','generation_id':job['generation_id'],
        'repository_path':path,'sha256':sha(p),'prompt':request['prompt'],'request':job['request'],
        'request_sha256':job['request_sha256'],'references':refs,'transparent_background':True,
        'selected':True,'native_pixel_edits':False}
    with Image.open(p) as im:
        assert im.mode=='RGBA' and list(im.size)==job['native_size'] and max(im.size)<=1536
        w,h=im.size;alpha=im.getchannel('A');mask=alpha.point(lambda v:255 if v>16 else 0)
        box=mask.getbbox();assert box
        margins=[box[0],box[1],w-box[2],h-box[3]];assert min(margins)>=4
        body_height=box[3]-box[1]
        feet=mask.crop((0,box[3]-int(body_height*.23),w,box[3])).getbbox();assert feet
        pivot=[(feet[0]+feet[2])/2,box[3]-4]
        zero_fraction=alpha.histogram()[0]/(w*h)
    verified=False
    if receipt:
        check=dimensions[path]
        assert check['passed'] and [check['width'],check['height']]==[w,h]
        assert any(r['path']==path and r['before_sha256']==sha(p)==r['after_sha256'] for r in receipt['source_files'])
        verified=True
    source_key='idle_'+d
    sources[source_key]={'path':path,'sha256':sha(p),'job':jp.stem,'mode':'RGBA','native_size':[w,h],
        'imported_size':[w,h],'import_limit':1536,'import_dimensions_verified':verified,
        'import_dimension_status':'independently verified native texture dimensions' if verified else 'expected until independent Godot receipt',
        'full_atlas':True,'alpha_zero_fraction':zero_fraction}
    virtual=max(w,h)
    poses['idle_'+d]={'source':source_key,'region_raw':[0,0,w,h],'region':[0,0,w,h],
        'margin':[0,0,virtual-w,virtual-h],'virtual_size_imported':virtual,'pivot':pivot,
        'draw_offset_px':[virtual*.5-pivot[0],virtual*.82-pivot[1]],
        'draw_scale':round(virtual*.70/body_height,6)}
    bounds.append({'direction':d,'source_sha256':sha(p),'visible_alpha_threshold':16,
        'visible_bounds':box,'visible_margins':margins,'requested_padding_80_met':min(margins)>=80,
        'pivot':pivot,'foot_anchor_status':'Lower silhouette estimate; original motion/campaign review remains open'})
    desc=Path(str(p)+'.import')
    if not desc.exists():
        a=hashlib.md5(('res://'+seed).encode()).hexdigest();b=hashlib.md5(('res://'+path).encode()).hexdigest()
        text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(seed,path).replace(Path(seed).name+'-'+a,p.name+'-'+b)
        desc.write_text(text,encoding='utf-8',newline='\n')
character=f'zhu_wounded_v4_{key}_fullidle'
manifest={'schema':'native_direction4_spriteframes_v1','character':character,'identity_key':key,
    'display_context':'rescued idle candidate','sources':sources,'states':{'idle':['idle']},'poses':poses,
    'resources':[f'assets/anim/{character}_idle_{d}.tres' for d in DIRS],
    'scope':'Four full-canvas short-sturdy adult idle candidates; anatomy/wardrobe/actions and original-game routing require review',
    'revision':'character_traits_v4','posture_profile':f'tools/contracts/zhu_wounded_20261005/character_posture_profiles_v4.json#{key}',
    'production_qualified':False}
write(ROOT/f'assets/direction4/zhu_wounded_{key}_20261006_fullidle_v4.json',manifest)
write(HERE/f'generation_{key}_fullidle_v4.json',{'original_reference':lineage['original_reference'],
    'jobs':list(graph.values()),'scope':'Retained native ancestry plus new full-canvas idle templates; parent images unchanged'})
write(ROOT/f'qa/zhu_wounded_20261005/{key}_fullidle_sampling_v4.json',{'checks':bounds,
    'scope':'Read-only native source geometry and initial short-stature draw metadata; no action qualification','production_qualified':False})
print(json.dumps({'sources':4,'poses':4,'resources':4,'import_dimensions_verified':all(s['import_dimensions_verified'] for s in sources.values()),'production_qualified':False}))
