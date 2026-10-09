"""Derive seven native upright idle candidates and portable lineage; PNGs read only.

Before native import, dimensions are expected only. Pass an independent import
receipt to mark texture dimensions verified before generating SpriteFrames.
"""
from pathlib import Path
import argparse, hashlib, json, re, subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
DIRS = ('se','sw','ne','nw')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--import-receipt', type=Path)
parser.add_argument('--selection',type=Path)
parser.add_argument('--revision',choices=('v3','v4'),default='v3')
parser.add_argument('--identity-authoring',type=Path)
parser.add_argument('--context',choices=('rescued','ordinary'),default='rescued')
parser.add_argument('--character',help='Select one explicitly recorded character for independent import')
args = parser.parse_args()
assert args.context=='rescued' or args.revision=='v4' and args.identity_authoring
if (ROOT/'qa/zhu_wounded_20261005/user_character_traits_review_v4.json').exists() and args.revision=='v3':
    raise RuntimeError('Blanket soldier v3 selection superseded; retain historical resources and use explicit v4 character selection.')
if args.revision=='v4':assert args.selection,'Individual v4 selection required'
selection = json.loads((args.selection or HERE/'selection_idle_v3.json').read_text(encoding='utf-8'))
identity = json.loads((args.identity_authoring or HERE/'authoring.json').read_text(encoding='utf-8'))['characters']
baseline = selection['baseline']
baseline_refs = {ref['path']: ref['sha256'] for character in identity.values() for ref in character['references']}
records = {}
for jp in sorted((HERE/'jobs').glob('*.json')):
    job = json.loads(jp.read_text(encoding='utf-8'))
    output = job.get('output',job.get('repository_input')) if isinstance(job,dict) else None
    if output: records[output] = (jp.stem, job)
dimensions = {}
if args.import_receipt:
    receipt = json.loads(args.import_receipt.read_text(encoding='utf-8'))
    assert receipt['complete'] and receipt['dimensions']['passed'] and receipt['lock_released']
    dimensions = {row['path']:row for row in receipt['dimensions']['checks']}
def reference_relative(recorded_path):
    # Archived exact requests retain their original host paths. Match their
    # complete repository-relative suffix against hashed known ancestry so a
    # different checkout location can reproduce metadata without editing them.
    normalized = recorded_path.replace('\\','/').lower()
    known = set(records) | set(baseline_refs)
    matches = [path for path in known if normalized==path.lower() or normalized.endswith('/'+path.lower())]
    assert len(matches)==1, 'Ambiguous or unknown archived reference: '+recorded_path
    return matches[0]
seed = 'assets/characters/shi_qian_bound_20261005/bound.png'
seed_text = Path(str(ROOT/seed)+'.import').read_text(encoding='utf-8')
counts = []
if args.character:
    assert args.character in selection['characters']
    selection['characters']={args.character:selection['characters'][args.character]}
for key, selected in selection['characters'].items():
    original = identity[key]['references'][0]['path']
    assert sha(ROOT/original) == identity[key]['references'][0]['sha256']
    graph = {}
    def add_job(path):
        if path == original: return 'original'
        if path in baseline_refs:
            reference_key = 'baseline_ref_'+hashlib.sha256(path.encode()).hexdigest()[:12]
            if reference_key not in graph:
                blob = subprocess.run(['git','show',baseline+':'+path], cwd=ROOT, check=True, capture_output=True).stdout
                assert hashlib.sha256(blob).hexdigest() == sha(ROOT/path) == baseline_refs[path]
                graph[reference_key] = {'key':reference_key,'method':'retained_identity_reference',
                    'generation_id':None,'repository_path':path,'sha256':baseline_refs[path],
                    'baseline_commit':baseline,'reference_role':'Existing committed artwork retained as identity or anatomy ancestry; no new generation prompt claimed.',
                    'references':[],'selected':False,'native_pixel_edits':False}
            return reference_key
        assert path in records, 'Missing native generation ancestry: '+path
        jobkey, job = records[path]
        if jobkey in graph: return jobkey
        native_sha = job.get('output_sha256',job.get('sha256'))
        assert sha(ROOT/path) == native_sha
        request = job.get('request',job.get('request_file'))
        rp = ROOT/request if request.startswith('tools/') else HERE/request
        assert sha(rp) == job['request_sha256']
        request_args = json.loads(rp.read_text(encoding='utf-8'))
        refs = [add_job(reference_relative(p)) for p in request_args.get('referenced_image_paths',[])]
        graph[jobkey] = {'key':jobkey, 'method':'built_in_imagegen', 'generation_id':job['generation_id'],
                         'repository_path':path, 'sha256':native_sha, 'prompt':request_args['prompt'],
                         'request':rp.relative_to(ROOT).as_posix(), 'request_sha256':sha(rp),
                         'references':refs, 'transparent_background':request_args['transparent_background'],
                         'selected':jobkey==selected['job'], 'native_pixel_edits':False}
        return jobkey
    path, job = next((path,job) for path,(name,job) in records.items() if name==selected['job'])
    assert path == selected['path'] and sha(ROOT/path) == selected['sha256']
    bounds = json.loads((ROOT/selected['bounds_receipt']).read_text(encoding='utf-8'))
    assert bounds['passed'] and bounds['sha256'] == selected['sha256']
    with Image.open(ROOT/path) as im:
        assert im.mode=='RGBA' and max(im.size)<=1536
        native_size = list(im.size)
        alpha = im.getchannel('A')
        poses, bound_rows = {}, []
        for row, direction in enumerate(DIRS):
            width,height=im.width//2,im.height//2
            x=(row%2)*width; y=(row//2)*height
            sample=alpha.crop((x,y,x+width,y+height))
            bbox=sample.point(lambda value:255 if value>16 else 0).getbbox()
            assert bbox and min(bbox[0],bbox[1],width-bbox[2],height-bbox[3])>=4
            body_height=bbox[3]-bbox[1]
            feet=sample.crop((0,bbox[3]-int(body_height*.23),width,bbox[3])).point(lambda value:255 if value>16 else 0).getbbox()
            assert feet
            pivot=[(feet[0]+feet[2])/2,bbox[3]-4]
            virtual=max(width,height); pad_x=(virtual-width)//2;pad_y=(virtual-height)//2
            body_fraction=.70 if key=='wang_ying' else .78
            poses['idle_'+direction]={'source':'idle','region_raw':[x,y,width,height], 'region':[x,y,width,height],
                'margin':[pad_x,pad_y,virtual-width,virtual-height], 'virtual_size_imported':virtual,
                'pivot':pivot,'draw_offset_px':[virtual*.5-(pad_x+pivot[0]),virtual*.82-(pad_y+pivot[1])],
                'draw_scale':round(virtual*body_fraction/body_height,6)}
            bound_rows.append({'direction':direction,'bounds':list(bbox),'pivot':pivot,'foot_anchor_status':'Initial lower-silhouette estimate; actual feet and animated gait review pending'})
        zero_fraction=alpha.histogram()[0]/(im.width*im.height)
    verified=False
    if args.import_receipt:
        dimension=dimensions[path]
        assert dimension['passed'] and [dimension['width'],dimension['height']]==native_size
        assert any(r['path']==path and r['before_sha256']==selected['sha256']==r['after_sha256'] for r in receipt['source_files'])
        verified=True
    source={'path':path,'sha256':selected['sha256'],'job':add_job(path),'mode':'RGBA',
            'native_size':native_size,'imported_size':native_size,'import_limit':1536,
            'import_dimension_status':'independently verified native texture dimensions' if verified else 'expected until independent Godot receipt',
            'import_dimensions_verified':verified,'full_atlas':True,'alpha_zero_fraction':zero_fraction}
    desc=Path(str(ROOT/path)+'.import')
    if not desc.exists():
        old_md5=hashlib.md5(('res://'+seed).encode()).hexdigest()
        new_md5=hashlib.md5(('res://'+path).encode()).hexdigest()
        text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(seed,path).replace('bound.png-'+old_md5,Path(path).name+'-'+new_md5)
        desc.write_text(text,encoding='utf-8',newline='\n')
    character='zhu_wounded_'+args.revision+'_'+key
    if args.context=='ordinary': character='character_traits_'+args.revision+'_'+key
    manifest={'schema':'native_direction4_spriteframes_v1','character':character,
              'sources':{'idle':source},'states':{'idle':['idle']},'poses':poses,
              'resources':[f'assets/anim/{character}_idle_{direction}.tres' for direction in DIRS],
              'scope':'Four independent rescued idle candidates; individual posture profile applies; walk/continuous gait/actual campaign pending',
              'revision':'upright_soldier_v3' if args.revision=='v3' else 'character_traits_v4','production_qualified':False}
    if args.revision=='v4':manifest['posture_profile']='tools/contracts/zhu_wounded_20261005/character_posture_profiles_v4.json#'+key
    if args.context=='ordinary':manifest['scope']='Four ordinary upright idle candidates; no original-game routing/actions/UI or continuous gait qualification'
    manifest_name=f'zhu_wounded_{key}_20261005_v3.json' if args.revision=='v3' else f'zhu_wounded_{key}_20261006_traits_v4.json'
    if args.context=='ordinary':manifest_name=f'ordinary_{key}_20261006_traits_v4.json'
    write(ROOT/'assets/direction4'/manifest_name,manifest)
    write(HERE/f'generation_{key}_{args.revision}.json',{'original_reference':{'path':original,'sha256':sha(ROOT/original)},
        'jobs':list(graph.values()),'scope':'Complete required ancestry retained; historical rejected pixels are edit parents only, not selected as runtime frames.'})
    write(ROOT/'qa/zhu_wounded_20261005'/f'{key}_idle_sampling_{args.revision}.json',{'source':path,'source_sha256':selected['sha256'],
        'checks':bound_rows,'scope':'Read-only source regions and initial draw metadata; not runtime foot qualification','production_qualified':False})
    counts.append({'character':key,'poses':4,'resources':4,'import_dimensions_verified':verified})
print(json.dumps({'characters':counts,'total_poses':len(counts)*4,'production_qualified':False}))
