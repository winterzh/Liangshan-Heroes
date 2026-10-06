"""Build Shi Qian traits full four-phase candidates from native atlas and single sources."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
DIRS=('se','sw','ne','nw')
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--import-receipt',type=Path)
args=parser.parse_args()
baseline=read(HERE/'selection_idle_v3.json')['baseline']
identities=read(HERE/'authoring.json')['characters']
baseline_refs={r['path']:r['sha256'] for c in identities.values() for r in c['references']}
original=identities['shi_qian']['references'][0]['path'];assert sha(ROOT/original)==baseline_refs[original]
records={}
for jp in sorted((HERE/'jobs').glob('*.json')):
    j=read(jp);output=j.get('output',j.get('repository_input')) if isinstance(j,dict) else None
    if output:records[output]=(jp.stem,j)
def relative(recorded):
    normalized=recorded.replace('\\','/').lower()
    matches=[p for p in set(records)|set(baseline_refs) if normalized==p.lower() or normalized.endswith('/'+p.lower())]
    assert len(matches)==1,recorded
    return matches[0]
graph={}
def ancestor(path):
    if path==original:return 'original'
    if path in baseline_refs:
        key='baseline_ref_'+hashlib.sha256(path.encode()).hexdigest()[:12]
        if key not in graph:
            blob=subprocess.run(['git','show',baseline+':'+path],cwd=ROOT,capture_output=True,check=True,timeout=10).stdout
            assert hashlib.sha256(blob).hexdigest()==sha(ROOT/path)==baseline_refs[path]
            graph[key]={'key':key,'method':'retained_identity_reference','generation_id':None,
                'repository_path':path,'sha256':baseline_refs[path],'baseline_commit':baseline,
                'reference_role':'Retained original character identity/anatomy reference; no new generation prompt claimed',
                'references':[],'selected':False,'native_pixel_edits':False}
        return key
    key,job=records[path]
    if key in graph:return key
    digest=job.get('output_sha256',job.get('sha256'));assert sha(ROOT/path)==digest
    if job.get('method') in ('godot_3d_pose_reference','orthographic_geometry_diagram'):
        assert job['generator_artifacts'] and not job['references']
        for artifact in job['generator_artifacts']:assert sha(ROOT/artifact['path'])==artifact['sha256']
        graph[key]={'key':key,'method':job['method'],'generation_id':None,'repository_path':path,
            'sha256':digest,'prompt':job['prompt'],'references':[],
            'generator_artifacts':job['generator_artifacts'],'selected':False,'native_pixel_edits':False}
        return key
    req=job.get('request',job.get('request_file'));rp=ROOT/req if req.startswith('tools/') else HERE/req
    assert sha(rp)==job['request_sha256'];request=read(rp)
    refs=[ancestor(relative(p)) for p in request.get('referenced_image_paths',[])]
    graph[key]={'key':key,'method':'built_in_imagegen','generation_id':job['generation_id'],
        'repository_path':path,'sha256':digest,'prompt':request['prompt'],'request':rp.relative_to(ROOT).as_posix(),
        'request_sha256':sha(rp),'references':refs,'transparent_background':request['transparent_background'],
        'selected':False,'native_pixel_edits':False}
    return key
receipt=read(args.import_receipt) if args.import_receipt else None;dimensions={}
if receipt:
    assert receipt['complete'] and receipt['lock_released'] and receipt['dimensions']['passed']
    dimensions={c['path']:c for c in receipt['dimensions']['checks']}
sources={};poses={};rows=[]
seed='assets/characters/shi_qian_wounded_20261005/idle_traits_v4.png'
seed_text=Path(str(ROOT/seed)+'.import').read_text(encoding='utf-8')
for state in ('idle','walk_a','passing_a','walk_b','passing_b'):
    for index,d in enumerate(DIRS):
        name={'idle':'shi_qian_idle_traits_v4','walk_a':'shi_qian_walk_a_spacing_atlas_v4','walk_b':f'shi_qian_walk_b_geometry_{d}_v4','passing_a':f'shi_qian_passing_a_geometry_{d}_v4','passing_b':f'shi_qian_passing_b_geometry_{d}_v4'}[state]
        if state=='walk_b' and d=='nw':name='shi_qian_walk_b2_geometry_nw_v4'
        j=read(HERE/f'jobs/{name}.json');path=j['output'];p=ROOT/path;assert sha(p)==j['output_sha256']
        key=state+'_'+d;job_key=ancestor(path);graph[job_key]['selected']=True
        with Image.open(p) as im:
            assert im.mode=='RGBA' and im.size==(1254,1254)
            w,h=im.size;alpha=im.getchannel('A');mask=alpha.point(lambda v:255 if v>16 else 0)
            if state in ('idle','walk_a'):x,y,cw,ch=(index%2)*627,(index//2)*627,627,627
            else:x,y,cw,ch=0,0,w,h
            cell=mask.crop((x,y,x+cw,y+ch));box=cell.getbbox();assert box
            assert min(box[0],box[1],cw-box[2],ch-box[3])>=4
            body_height=box[3]-box[1]
            feet=cell.crop((0,box[3]-int(body_height*.23),cw,box[3])).getbbox();assert feet
            pivot=[(feet[0]+feet[2])/2,box[3]-4];zero_fraction=alpha.histogram()[0]/(w*h)
        verified=False
        if receipt:
            check=dimensions[path]
            assert check['passed'] and [check['width'],check['height']]==[w,h]
            assert any(c['path']==path and c['before_sha256']==sha(p)==c['after_sha256'] for c in receipt['source_files'])
            verified=True
        source_key=job_key
        sources[source_key]={'path':path,'sha256':sha(p),'job':job_key,'mode':'RGBA','native_size':[w,h],
            'imported_size':[w,h],'import_limit':1536,'import_dimensions_verified':verified,
            'import_dimension_status':'independently verified native texture dimensions' if verified else 'expected until independent Godot receipt',
            'full_atlas':True,'alpha_zero_fraction':zero_fraction}
        poses[key]={'source':source_key,'region_raw':[x,y,cw,ch],'region':[x,y,cw,ch],'margin':[0,0,0,0],
            'virtual_size_imported':cw,'pivot':pivot,'draw_offset_px':[cw*.5-pivot[0],cw*.82-pivot[1]],
            'draw_scale':round(cw*.78/body_height,6)}
        rows.append({'pose':key,'bounds_relative_to_region':box,'region':[x,y,cw,ch],'pivot':pivot,
            'foot_anchor_status':'Initial lower-silhouette estimate only; true planted-foot motion requires review'})
        desc=Path(str(p)+'.import')
        if not desc.exists():
            a=hashlib.md5(('res://'+seed).encode()).hexdigest();b=hashlib.md5(('res://'+path).encode()).hexdigest()
            text=re.sub(r'^uid=.*\n','',seed_text,flags=re.M).replace(seed,path).replace(Path(seed).name+'-'+a,p.name+'-'+b)
            desc.write_text(text,encoding='utf-8',newline='\n')
character='zhu_wounded_v4_shi_qian_gait_traits'
m={'schema':'native_direction4_spriteframes_v1','character':character,'identity_key':'shi_qian',
    'sources':sources,'poses':poses,'states':{'idle':['idle'],'walk':['walk_a','passing_a','walk_b','passing_b']},
    'resources':[f'assets/anim/{character}_{state}_{d}.tres' for state in ('idle','walk') for d in DIRS],
    'revision':'character_traits_v4','posture_profile':'tools/contracts/zhu_wounded_20261005/character_posture_profiles_v4.json#shi_qian',
    'scope':'Twenty native poses from fourteen sources: two four-view idle/A atlases and twelve individually authored B/passing frames. Actual gait continuity, own-key Unit and original campaign remain open.',
    'candidate_only':True,'continuous_gait_qualified':False,'production_qualified':False}
write(ROOT/'assets/direction4/zhu_wounded_shi_qian_20261006_walk_passing_v4.json',m)
write(HERE/'generation_shi_qian_walk_passing_v4.json',{'original_reference':{'path':original,'sha256':sha(ROOT/original)},
    'jobs':list(graph.values()),'scope':'Native complete ancestry plus new mathematical geometry references; complete candidate four-phase gait only; no production routing'})
write(ROOT/'qa/zhu_wounded_20261005/shi_qian_walk_passing_sampling_v4.json',{'checks':rows,'candidate_only':True,'production_qualified':False})
print(json.dumps({'native_sources':len(sources),'poses':len(poses),'resources':8,'import_dimensions_verified':all(s['import_dimensions_verified'] for s in sources.values()),'candidate_only':True,'production_qualified':False}))
