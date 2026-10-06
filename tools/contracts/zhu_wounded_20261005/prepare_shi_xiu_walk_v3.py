"""Build isolated Shi Xiu gait candidate metadata; read PNGs, never alter pixels."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--import-receipt',type=Path)
parser.add_argument('--revision',choices=('v3','v4'),default='v3')
parser.add_argument('--phase-b',choices=('cloth','body2','matched','passing','refined','footclear'),default='cloth')
args=parser.parse_args()
version=args.revision
assert args.phase_b=='cloth' or version=='v4'
slot=version if args.phase_b=='cloth' else args.phase_b+'_'+version
full_phases=args.phase_b in ('passing','refined','footclear')
baseline=json.loads((HERE/'selection_idle_v3.json').read_text(encoding='utf-8'))['baseline']
identities=json.loads((HERE/'authoring.json').read_text(encoding='utf-8'))['characters']
baseline_refs={r['path']:r['sha256'] for c in identities.values() for r in c['references']}
original=identities['shi_xiu']['references'][0]['path']
assert sha(ROOT/original)==baseline_refs[original]
records={}
for p in sorted((HERE/'jobs').glob('*.json')):
    j=json.loads(p.read_text(encoding='utf-8'))
    output=j.get('output',j.get('repository_input')) if isinstance(j,dict) else None
    if output: records[output]=(p.stem,j)
graph={}
selected={'shi_xiu_idle_spacing_v3','shi_xiu_walk_a_v3','shi_xiu_step_b_transfer_v3',
          'shi_xiu_step_b_transfer_sw_v3','shi_xiu_step_b_transfer_ne_v3','shi_xiu_step_b_transfer_nw_v3'}
if version=='v4':
    selected={'shi_xiu_idle_spacing_v3','shi_xiu_walk_a_v3'}|{f'shi_xiu_step_b_{args.phase_b}_{d}_v4' for d in ('se','sw','ne','nw')}
    if args.phase_b=='matched':
        selected={'shi_xiu_idle_spacing_matched_v4'}|{f'shi_xiu_{phase}_{d}_v4' for phase in ('walk_a_matched','step_b_body2') for d in ('se','sw','ne','nw')}
        selected.discard('shi_xiu_walk_a_matched_nw_v4')
        selected.add('shi_xiu_walk_a_matched_nw2_v4')
    if full_phases:
        selected={f'shi_xiu_{phase}_{d}_v4' for phase in ('walk_a_matched','step_b_body2','passing_a','passing_b','idle_single') for d in ('se','sw','ne','nw')}
        selected.discard('shi_xiu_walk_a_matched_nw_v4')
        selected.add('shi_xiu_walk_a_matched_nw2_v4')
        selected.discard('shi_xiu_passing_b_sw_v4')
        selected.add('shi_xiu_passing_b2_sw_v4')
        selected.discard('shi_xiu_passing_b_ne_v4')
        selected.add('shi_xiu_passing_b2_ne_v4')
        selected.discard('shi_xiu_passing_b_nw_v4')
        selected.add('shi_xiu_passing_b_explicit_nw_v4')
        if args.phase_b in ('refined','footclear'):
            for d in ('sw','ne'):
                selected.discard(f'shi_xiu_passing_b2_{d}_v4')
                selected.add(f'shi_xiu_passing_b3_{d}_v4')
        if args.phase_b=='footclear':
            selected.discard('shi_xiu_passing_b3_sw_v4')
            selected.add('shi_xiu_passing_b5_sw_v4')
def relative(recorded):
    value=recorded.replace('\\','/').lower()
    matches=[p for p in set(records)|set(baseline_refs) if value==p.lower() or value.endswith('/'+p.lower())]
    assert len(matches)==1,recorded
    return matches[0]
def ancestry(path):
    if path==original: return 'original'
    if path in baseline_refs:
        key='baseline_ref_'+hashlib.sha256(path.encode()).hexdigest()[:12]
        if key not in graph:
            blob=subprocess.run(['git','show',baseline+':'+path],cwd=ROOT,capture_output=True,check=True,timeout=10).stdout
            assert hashlib.sha256(blob).hexdigest()==sha(ROOT/path)==baseline_refs[path]
            graph[key]={'key':key,'method':'retained_identity_reference','generation_id':None,
                'repository_path':path,'sha256':baseline_refs[path],'baseline_commit':baseline,
                'reference_role':'Retained committed identity/anatomy ancestry; no new generation prompt claimed.',
                'references':[],'selected':False,'native_pixel_edits':False}
        return key
    key,job=records[path]
    if key in graph: return key
    digest=job.get('output_sha256',job.get('sha256'))
    assert sha(ROOT/path)==digest
    req=job.get('request',job.get('request_file'))
    rp=ROOT/req if req.startswith('tools/') else HERE/req
    assert sha(rp)==job['request_sha256']
    request=json.loads(rp.read_text(encoding='utf-8'))
    refs=[ancestry(relative(p)) for p in request.get('referenced_image_paths',[])]
    graph[key]={'key':key,'method':'built_in_imagegen','generation_id':job['generation_id'],
        'repository_path':path,'sha256':digest,'prompt':request['prompt'],
        'request':rp.relative_to(ROOT).as_posix(),'request_sha256':sha(rp),'references':refs,
        'transparent_background':request['transparent_background'],'selected':key in selected,'native_pixel_edits':False}
    return key

idle_path='assets/direction4/zhu_wounded_shi_xiu_20261006_traits_v4.json' if args.phase_b=='matched' else 'assets/direction4/zhu_wounded_shi_xiu_20261005_v3.json'
sources={};poses={}
if not full_phases:
    idle=json.loads((ROOT/idle_path).read_text(encoding='utf-8'))
    sources={'idle':idle['sources']['idle']}
    poses=dict(idle['poses'])
    ancestry(sources['idle']['path'])
receipt=json.loads(args.import_receipt.read_text(encoding='utf-8')) if args.import_receipt else None
if receipt:
    assert receipt['complete'] and receipt['dimensions']['passed'] and receipt['lock_released']
dimensions={r['path']:r for r in receipt['dimensions']['checks']} if receipt else {}
seed='assets/characters/shi_qian_bound_20261005/bound.png'
seed_text=Path(str(ROOT/seed)+'.import').read_text(encoding='utf-8')
candidate=json.loads((QA/'shi_xiu_walk_transfer_v3.json').read_text(encoding='utf-8'))
chosen={'walk_a':candidate['phase_a_reference']['path']}
chosen.update({'walk_b_'+d:r['path'] for d,r in candidate['phase_b_candidates'].items()})
if version=='v4':
    chosen.update({'walk_b_'+d:f'assets/characters/shi_xiu_wounded_20261005/step_b_{args.phase_b}_{d}_v4.png' for d in ('se','sw','ne','nw')})
    if args.phase_b in ('matched','passing','refined','footclear'):
        chosen={'walk_a_'+d:f'assets/characters/shi_xiu_wounded_20261005/walk_a_matched_{d}_v4.png' for d in ('se','sw','ne','nw')}
        chosen['walk_a_nw']='assets/characters/shi_xiu_wounded_20261005/walk_a_matched_nw2_v4.png'
        chosen.update({'walk_b_'+d:f'assets/characters/shi_xiu_wounded_20261005/step_b_body2_{d}_v4.png' for d in ('se','sw','ne','nw')})
        if full_phases:
            chosen.update({phase+'_'+d:f'assets/characters/shi_xiu_wounded_20261005/{phase}_{d}_v4.png' for phase in ('passing_a','passing_b','idle_single') for d in ('se','sw','ne','nw')})
            chosen['passing_b_sw']='assets/characters/shi_xiu_wounded_20261005/passing_b2_sw_v4.png'
            chosen['passing_b_ne']='assets/characters/shi_xiu_wounded_20261005/passing_b2_ne_v4.png'
            chosen['passing_b_nw']='assets/characters/shi_xiu_wounded_20261005/passing_b_explicit_nw_v4.png'
            if args.phase_b in ('refined','footclear'):
                for d in ('sw','ne'):
                    chosen['passing_b_'+d]=f'assets/characters/shi_xiu_wounded_20261005/passing_b3_{d}_v4.png'
            if args.phase_b=='footclear':
                chosen['passing_b_sw']='assets/characters/shi_xiu_wounded_20261005/passing_b5_sw_v4.png'
rows=[]
for key,path in chosen.items():
    with Image.open(ROOT/path) as im:
        assert im.mode=='RGBA' and max(im.size)<=1536
        size=list(im.size);alpha=im.getchannel('A');fraction=alpha.histogram()[0]/(im.width*im.height)
        assert fraction>.35
        dirs=('se','sw','ne','nw') if key=='walk_a' else (key[-2:],)
        for index,d in enumerate(dirs):
            w,h=(im.width//2,im.height//2) if key=='walk_a' else im.size
            x,y=((index%2)*w,(index//2)*h) if key=='walk_a' else (0,0)
            a=alpha.crop((x,y,x+w,y+h))
            bbox=a.point(lambda v:255 if v>16 else 0).getbbox()
            assert bbox and min(bbox[0],bbox[1],w-bbox[2],h-bbox[3])>=4
            height=bbox[3]-bbox[1];virtual=max(w,h)
            feet=a.crop((0,bbox[3]-int(height*.23),w,bbox[3])).point(lambda v:255 if v>16 else 0).getbbox()
            assert feet
            pivot=[(feet[0]+feet[2])/2,bbox[3]-4]
            px=(virtual-w)//2;py=(virtual-h)//2
            pose_key=('walk_a_' if key.startswith('walk_a') else 'walk_b_')+d
            if full_phases:pose_key=key.replace('idle_single_','idle_')
            poses[pose_key]={'source':key,'region_raw':[x,y,w,h],'region':[x,y,w,h],
                'margin':[px,py,virtual-w,virtual-h],'virtual_size_imported':virtual,'pivot':pivot,
                'draw_offset_px':[virtual*.5-(px+pivot[0]),virtual*.82-(py+pivot[1])],
                'draw_scale':round(virtual*.78/height,6)}
            rows.append({'pose':pose_key,'bounds':list(bbox),'pivot':pivot,
                'foot_status':'Initial lower-silhouette estimate only; actual animation correction pending'})
    verified=False
    if receipt:
        row=dimensions[path]
        assert row['passed'] and [row['width'],row['height']]==size
        assert any(r['path']==path and r['before_sha256']==sha(ROOT/path)==r['after_sha256'] for r in receipt['source_files'])
        verified=True
    sources[key]={'path':path,'sha256':sha(ROOT/path),'job':ancestry(path),'mode':'RGBA','native_size':size,
        'imported_size':size,'import_limit':1536,'import_dimensions_verified':verified,
        'import_dimension_status':'independently verified' if verified else 'expected until independent import',
        'full_atlas':True,'alpha_zero_fraction':fraction}
    desc=Path(str(ROOT/path)+'.import')
    if not desc.exists():
        a=hashlib.md5(('res://'+seed).encode()).hexdigest();b=hashlib.md5(('res://'+path).encode()).hexdigest()
        text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(seed,path).replace('bound.png-'+a,Path(path).name+'-'+b)
        desc.write_text(text,encoding='utf-8',newline='\n')
character=f'zhu_wounded_{version}_shi_xiu_gait'
if args.phase_b!='cloth':character+='_'+args.phase_b
manifest={'schema':'native_direction4_spriteframes_v1','character':character,'sources':sources,'poses':poses,
    'states':{'idle':['idle'],'walk':['walk_a','idle','walk_b','idle']},
    'resources':[f'assets/anim/{character}_{state}_{d}.tres' for state in ('idle','walk') for d in ('se','sw','ne','nw')],
    'scope':'Isolated upright gait candidate: A/idle/B/idle reuses stationary idle as near-foot transition, not newly authored passing frames. No production routing or continuous acceptance.',
    'revision':'upright_soldier_v3' if version=='v3' else 'character_traits_v4','production_qualified':False}
if version=='v4': manifest['posture_profile']='tools/contracts/zhu_wounded_20261005/character_posture_profiles_v4.json#shi_xiu'
if full_phases:
    manifest['states']={'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']}
    manifest['scope']='Twenty full-canvas native sources: four idle views and four independently authored gait phases per direction. Passing/body continuity and actual Unit/campaign qualification pending.'
write(ROOT/f'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_{slot}.json',manifest)
write(HERE/f'generation_shi_xiu_walk_{slot}.json',{'original_reference':{'path':original,'sha256':sha(ROOT/original)},
    'jobs':list(graph.values()),'scope':'Complete required native ancestry; old pose art supplies only explicit lower-body guide.'})
write(QA/f'shi_xiu_walk_sampling_{slot}.json',{'checks':rows,'scope':'Read-only sampling and initial metadata; not visual gait/foot qualification','production_qualified':False})
print(json.dumps({'sources':len(sources),'poses':len(poses),'resources':8,
    'new_import_dimensions_verified':all(s['import_dimensions_verified'] for s in sources.values()),'production_qualified':False}))
